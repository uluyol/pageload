package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/golang/protobuf/proto"
	"github.com/uluyol/pageload/cmd/mm/internal"
	pb "github.com/uluyol/pageload/cmd/mm/proto"
)

func main() {
	log.SetPrefix("get_index: ")
	log.SetFlags(0)

	saveDir := os.Args[1]

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
		firstLine := string(reqResp.Request.FirstLine)
		if !strings.HasPrefix(firstLine, "GET") {
			continue
		}

		host := internal.MustGetHeader(reqResp.Request, "Host")
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
		fmt.Println(url)
	}
}