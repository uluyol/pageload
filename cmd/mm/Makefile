.PHONY: proto

BINS := \
	bin/extract_records_index \
	bin/get_index \
	bin/list_resources \
	vaultbin/extract_records_index \
	vaultbin/get_index \
	vaultbin/list_resources

all: bins

proto: http_record_pb2.py proto/http_record.pb.go

http_record_pb2.py: http_record.proto
	protoc --python_out=. http_record.proto

proto/http_record.pb.go: http_record.proto
	mkdir -p proto
	protoc --go_out=proto/ http_record.proto

bin:
	mkdir bin || true

vaultbin:
	mkdir vaultbin || true

bins: $(BINS)

bin/%: %/* proto/http_record.pb.go bin
	GOBIN=$(CURDIR)/bin go install ./$*

vaultbin/%: %/* proto/* vaultbin
	cd vaultbin && GOOS=freebsd GOARCH=amd64 go build ../$*
