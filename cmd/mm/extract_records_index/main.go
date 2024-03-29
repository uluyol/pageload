package main

import (
	"bytes"
	"compress/gzip"
	"encoding/json"
	"flag"
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

// HARSchema is the schema for a HAR file that only includes
// the fields that we care about.
type HARSchema struct {
	Log struct {
		Entries []struct {
			Request struct {
				URL string
			}
		}
	}
}

type Result struct {
	Resources          []ResourceMeta `json:"resources"`
	IndexRedirectChain []string       `json:"indexRedirectChain"`
	IndexBody          string         `json:"indexBody"`
}

type ResourceMeta struct {
	Bytes        int64  `json:"bytes"`
	URL          string `json:"url"`
	ContentType  string `json:"contentType"`
	Referer      string `json:"referer"`
	CacheControl string `json:"cacheControl"`
}

func getResourceMeta(rr pb.RequestResponse) ResourceMeta {
	firstLine := string(rr.GetRequest().GetFirstLine())
	host := internal.MustGetHeader(rr.GetRequest(), "host")
	path := strings.Fields(strings.TrimSpace(strings.TrimPrefix(firstLine, "GET")))[0]

	var url string
	switch *rr.Scheme {
	case pb.RequestResponse_HTTP:
		url = "http://" + host + path
	case pb.RequestResponse_HTTPS:
		url = "https://" + host + path
	default:
		log.Fatalf("unknown scheme: %v", *rr.Scheme)
	}

	bytes := int64(len(rr.GetResponse().GetBody()))

	ctype, err := internal.GetHeader(rr.GetResponse(), "content-type")
	if err != nil {
		ctype = "unknown"
	}

	referer, err := internal.GetHeader(rr.GetRequest(), "referer")
	if err != nil {
		referer = ""
	}

	cacheControl, err := internal.GetHeader(rr.GetResponse(), "cache-control")
	if err != nil {
		cacheControl = ""
	}

	return ResourceMeta{
		Bytes:        bytes,
		URL:          url,
		ContentType:  ctype,
		Referer:      referer,
		CacheControl: cacheControl,
	}
}

func alwaysIncludeURL(u string) bool { return true }

func makeOnlyPreOnloadURLs(m map[string]bool) func(u string) bool {
	return func(u string) bool {
		return m[u]
	}
}

var onlyPreOnload = flag.Bool("preonload", true, "only include retreieved before the onload event")

func main() {
	flag.Parse()

	log.SetPrefix("extract_records_index: ")
	log.SetFlags(0)

	site := flag.Arg(0)
	runDir := flag.Arg(1)
	saveDirBase := flag.Arg(2)

	harPath := filepath.Join(runDir, "hars", saveDirBase)
	saveDir := filepath.Join(runDir, saveDirBase)

	includeURL := alwaysIncludeURL

	if *onlyPreOnload {
		var har HARSchema
		harData, err := ioutil.ReadFile(harPath)
		if err != nil {
			log.Fatalf("unable to read har data: %v", err)
		}
		if err := json.Unmarshal(harData, &har); err != nil {
			log.Fatalf("har data is invalid: %v", err)
		}
		preOnloadSet := make(map[string]bool)
		for _, e := range har.Log.Entries {
			preOnloadSet[e.Request.URL] = true
		}
		includeURL = makeOnlyPreOnloadURLs(preOnloadSet)
	}

	fis, err := ioutil.ReadDir(saveDir)
	if err != nil {
		log.Fatalf("unable to read dir: %v", err)
	}

	var result Result
	result.Resources = make([]ResourceMeta, 0, 10)

	// unmarshal request responses
	var reqResps []pb.RequestResponse
	for _, fi := range fis {
		save := filepath.Join(saveDir, fi.Name())
		var rr pb.RequestResponse
		data, err := ioutil.ReadFile(save)
		if err != nil {
			log.Printf("warn: unable to read %s: %v", save, err)
			continue
		}
		if err := proto.Unmarshal(data, &rr); err != nil {
			log.Printf("warn: unable to unmarshal %s: %v", save, err)
			continue
		}

		firstLine := string(rr.GetRequest().GetFirstLine())
		if !strings.HasPrefix(firstLine, "GET") {
			continue
		}

		rm := getResourceMeta(rr)

		if !includeURL(rm.URL) {
			continue
		}

		if strings.Contains(rm.URL, "://localhost") || strings.Contains(rm.URL, "://127.0.0.1") {
			continue
		}

		reqResps = append(reqResps, rr)
		result.Resources = append(result.Resources, rm)
	}

	var redirectChain []string
	var body string

LoopStart:
	for i, rr := range reqResps {
		if internal.CleanURL(result.Resources[i].URL) != internal.CleanURL(site) {
			continue
		}

		redirectChain = append(redirectChain, result.Resources[i].URL)

		code := strings.Fields(string(rr.GetResponse().FirstLine))
		switch code[1] {
		case "301", "302", "303":
			site = internal.MustGetHeader(rr.GetResponse(), "location")
			goto LoopStart
		}

		chunked := false
		gzipped := false
		for _, h := range rr.GetResponse().Header {
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

		var r io.Reader = bytes.NewReader(rr.GetResponse().Body)
		if chunked {
			r = internal.NewChunkedReader(r)
		}
		if gzipped {
			r, err = gzip.NewReader(r)
			if err != nil {
				log.Fatalf("unable to created gzip reader: %v", err)
			}
		}
		b, err := ioutil.ReadAll(r)
		if err != nil {
			log.Fatalf("unable to read index body: %v", err)
		}
		body = string(b)
	}

	result.IndexRedirectChain = redirectChain
	result.IndexBody = body

	enc := json.NewEncoder(os.Stdout)
	enc.Encode(&result)
}