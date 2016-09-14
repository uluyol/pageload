.PHONY: proto

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

bins: bin/get_index bin/list_resources vaultbin/get_index vaultbin/list_resources

bin/%: %/* proto/* bin
	GOBIN=$(CURDIR)/bin go install ./$*

vaultbin/%: %/* proto/* vaultbin
	cd vaultbin && GOOS=freebsd GOARCH=amd64 go build ../$*
