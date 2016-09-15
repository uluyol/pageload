package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"path/filepath"
	"strings"

	"github.com/golang/protobuf/proto"
	"github.com/uluyol/pageload/cmd/mm/internal"
	pb "github.com/uluyol/pageload/cmd/mm/proto"
)

var printContentType = flag.Bool("types", false, "print content-types of resources")
var skipIframeDeps = flag.Bool("noiframedeps", true, "don't show iframe dependencies")

func main() {
	log.SetPrefix("get_index: ")
	log.SetFlags(0)

	flag.Parse()

	indexURL := flag.Arg(0)
	saveDir := flag.Arg(1)

	fis, err := ioutil.ReadDir(saveDir)
	if err != nil {
		log.Fatalf("unable to read dir: %v", err)
	}

	var saves []string
	for _, fi := range fis {
		saves = append(saves, filepath.Join(saveDir, fi.Name()))
	}

	for _, s := range saves {
		reqResp := pb.RequestResponse{}
		data, err := ioutil.ReadFile(s)
		if err != nil {
			log.Fatal(err)
		}
		if err := proto.Unmarshal(data, &reqResp); err != nil {
			log.Fatal(err)
		}
		firstLine := string(reqResp.GetRequest().GetFirstLine())
		if !strings.HasPrefix(firstLine, "GET") {
			continue
		}

		host := internal.MustGetHeader(reqResp.GetRequest(), "Host")
		path := strings.Fields(strings.TrimSpace(strings.TrimPrefix(firstLine, "GET")))[0]

		var url string
		switch *reqResp.Scheme {
		case pb.RequestResponse_HTTP:
			url = "http://" + host + path
		case pb.RequestResponse_HTTPS:
			url = "https://" + host + path
		default:
			log.Fatalf("unknown scheme: %v", reqResp.Scheme)
		}

		referer, err := internal.GetHeader(reqResp.GetRequest(), "referer")
		if err != nil {
			referer = ""
		}

		if *skipIframeDeps && internal.CleanURL(referer) != internal.CleanURL(indexURL) {
			continue
		}

		if *printContentType {
			ctype, err := internal.GetHeader(reqResp.GetResponse(), "content-type")
			if err != nil {
				ctype = "unknown"
			}

			fmt.Printf("%s %s\n", url, ctype)
		} else {
			fmt.Println(url)
		}
	}
}