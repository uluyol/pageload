package main

import (
	"bytes"
	"compress/gzip"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/golang/protobuf/proto"
	"github.com/uluyol/pageload/cmd/mm/internal"
	pb "github.com/uluyol/pageload/cmd/mm/proto"
)

func matchesRequested(found, req string) bool {
	return internal.CleanURL(found) == internal.CleanURL(req)
}

var printURLs = flag.Bool("urls", false, "print urls navigated to instead of page body")

func main() {
	flag.Parse()

	log.SetPrefix("get_index: ")
	log.SetFlags(0)

	site := flag.Arg(0)
	saveDir := flag.Arg(1)

	fis, err := ioutil.ReadDir(saveDir)
	if err != nil {
		log.Fatalf("unable to read dir: %v", err)
	}

	var saves []string
	for _, fi := range fis {
		saves = append(saves, filepath.Join(saveDir, fi.Name()))
	}

LoopStart:
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

		if !matchesRequested(url, site) {
			continue
		}

		if *printURLs {
			fmt.Println(url)
		}

		code := strings.Fields(string(reqResp.GetResponse().FirstLine))
		switch code[1] {
		case "301", "302", "303":
			site = internal.MustGetHeader(reqResp.GetResponse(), "location")
			goto LoopStart
		}

		chunked := false
		gzipped := false
		for _, h := range reqResp.GetResponse().Header {
			if bytes.HasPrefix(bytes.ToLower(h.Key), []byte("transfer-encoding")) {
				if bytes.Equal(h.Value, []byte("chunked")) {
					chunked = true
				}
			}
			if bytes.HasPrefix(bytes.ToLower(h.Key), []byte("content-encoding")) {
				if bytes.Equal(h.Value, []byte("gzip")) {
					gzipped = true
				}
			}
		}

		var r io.Reader = bytes.NewReader(reqResp.GetResponse().Body)
		if chunked {
			r = internal.NewChunkedReader(r)
		}
		if gzipped {
			r, err = gzip.NewReader(r)
			if err != nil {
				log.Fatalf("unable to created gzip reader: %v", err)
			}
		}
		if !*printURLs {
			io.Copy(os.Stdout, r)
		}
	}
}