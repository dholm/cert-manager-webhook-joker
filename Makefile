IMAGE_NAME := "webhook"
IMAGE_TAG := "latest"

all: image.amd64 image.arm image.arm64

push: push.amd64 push.arm push.arm64

.PRECIOUS: cert-manager-webhook-joker.%
cert-manager-webhook-joker.%: main.go go.mod
	env GOOS=linux GOARCH=$(subst cert-manager-webhook-joker.,,$@) go build -o $@

verify:
	go test -v .

image.%: cert-manager-webhook-joker.%
	docker buildx build \
	  --platform linux/$(subst image.,,$@) \
	  --tag $(IMAGE_NAME):$(IMAGE_TAG)-$(subst image.,,$@) \
	  --file Dockerfile.$(subst image.,,$@) .

push.%: image.%
	docker push $(IMAGE_NAME):$(IMAGE_TAG)-$(subst push.,,$@)

clean:
	for i in amd64 arm arm64; do \
	  rm -f "cert-manager-webhook-joker.$${i}"; \
	  docker image rm -f $(IMAGE_NAME):$(IMAGE_TAG)-$${i}; \
	done

rendered-manifest.yaml:
	helm template \
	    --name example-webhook \
	--set image.repository=$(IMAGE_NAME) \
	--set image.tag=$(IMAGE_TAG) \
	deploy/example-webhook > "$(OUT)/rendered-manifest.yaml"

.PHONY: all verify image.% push.% clean rendered-manifest.yaml
