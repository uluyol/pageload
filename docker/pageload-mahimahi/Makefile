REPO = quay.io/uluyol/pageload-mahimahi
TAG = 0.8

.PHONY: build push

build:
	docker build -q -t $(REPO):$(TAG) .

push: build
	docker push $(REPO):$(TAG) >/dev/null
