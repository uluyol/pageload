REPO = quay.io/uluyol/pageload-mahimahi
TAG = 0.7

.PHONY: build push

build:
	docker build -q -t $(REPO):$(TAG) .

push: build
	docker push $(REPO):$(TAG) >/dev/null
