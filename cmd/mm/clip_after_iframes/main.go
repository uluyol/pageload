package main

import (
	"encoding/json"
	"flag"
	"log"
	"os"
	"sort"
	"strings"

	"github.com/uluyol/pageload/cmd/mm/internal"
)

type Result struct {
	Resources          []ResourceMeta `json:"resources"`
	IndexRedirectChain []string       `json:"indexRedirectChain"`
	IndexBody          string         `json:"indexBody"`
}

type ResourceMeta struct {
	Bytes       int64  `json:"bytes"`
	URL         string `json:"url"`
	ContentType string `json:"contentType"`
	Referer     string `json:"referer"`
}

type ResourceMetaSet map[ResourceMeta]struct{}

func NewResourceMetaSet() ResourceMetaSet {
	return ResourceMetaSet(make(map[ResourceMeta]struct{}))
}

func (set ResourceMetaSet) Add(e ResourceMeta) {
	set[e] = struct{}{}
}

func (set ResourceMetaSet) All() []ResourceMeta {
	members := make([]ResourceMeta, 0, 10)
	for e, _ := range set {
		members = append(members, e)
	}
	return members
}

func addRecursive(set ResourceMetaSet, refResMap map[string][]ResourceMeta, ref string, visited map[string]bool) {
	visited[ref] = true
	for _, rm := range refResMap[ref] {
		visited[rm.URL] = true
		set.Add(rm)
		if strings.Contains(rm.ContentType, "html") {
			continue
		}
		for ref, _ := range refResMap {
			if internal.CleanURL(ref) == internal.CleanURL(rm.URL) {
				addRecursive(set, refResMap, ref, visited)
			}
		}
	}
}

type byURL []ResourceMeta

func (s byURL) Len() int           { return len(s) }
func (s byURL) Swap(i, j int)      { s[i], s[j] = s[j], s[i] }
func (s byURL) Less(i, j int) bool { return s[i].URL < s[j].URL }

func main() {
	flag.Parse()

	log.SetPrefix("clip_after_iframes: ")
	log.SetFlags(0)

	var result Result
	dec := json.NewDecoder(os.Stdin)
	if err := dec.Decode(&result); err != nil {
		log.Fatalf("unable to decode result: %v", err)
	}

	refererResourceMap := make(map[string][]ResourceMeta)
	for _, res := range result.Resources {
		children := refererResourceMap[res.Referer]
		children = append(children, res)
		refererResourceMap[res.Referer] = children
	}

	set := NewResourceMetaSet()
	indexURL := result.IndexRedirectChain[len(result.IndexRedirectChain)-1]

	visited := make(map[string]bool)
	for ref, _ := range refererResourceMap {
		if internal.CleanURL(ref) == internal.CleanURL(indexURL) {
			// is root
			addRecursive(set, refererResourceMap, ref, visited)
		}
	}
	for ref, resources := range refererResourceMap {
		if !visited[ref] {
			// is rootless
			for _, r := range resources {
				set.Add(r)
			}
		}
	}

	result.Resources = set.All()
	sort.Sort(byURL(result.Resources))
	enc := json.NewEncoder(os.Stdout)
	enc.Encode(&result)
}
