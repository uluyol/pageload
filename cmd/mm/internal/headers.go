package internal

import (
	"bytes"
	"fmt"
	"strings"

	pb "github.com/uluyol/pageload/cmd/mm/proto"
)

func GetHeader(msg *pb.HTTPMessage, key string) (string, error) {
	lowKey := bytes.ToLower([]byte(key))
	for _, h := range msg.Header {
		if bytes.Equal(bytes.ToLower(h.Key), lowKey) {
			return string(h.Value), nil
		}
	}
	return "", fmt.Errorf("unable to find header %q", key)
}

func MustGetHeader(msg *pb.HTTPMessage, key string) string {
	s, e := GetHeader(msg, key)
	if e != nil {
		panic(e)
	}
	return s
}

func CleanURL(u string) string {
	u = strings.TrimSuffix(u, "/")
	u = strings.TrimPrefix(u, "http://")
	u = strings.TrimPrefix(u, "https://")
	u = strings.TrimPrefix(u, "www.")
	return u
}