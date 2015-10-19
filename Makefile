OWNER       := roboll
REPO        := skel

VERSION     := $(shell git describe --tags)
PROJECT     := github.com/$(OWNER)/$(REPO)

REGISTRY    :=

GOOS        := linux
GOARCH      := amd64

PRE_RELEASE := tag clean-repo test

.PHONY:  build docker release
build:   skel-linux-amd64 go.tar.gz javakit.tar.gz
docker:  build #none
release: $(PRE_RELEASE) docker gh-release-go.tar.gz gh-release-javakit.tar.gz

###############################################################################
# pre-release - test and validation
###############################################################################
.PHONY: test
test: ; go test ./...

###############################################################################
# build / release
###############################################################################
GOBUILD := GO15VENDOREXPERIMENT=1 GOOS=$(GOOS) GOARCH=$(GOARCH) go build
GOARGS  := -a -tags netgo -ldflags '-s -w -X main.release=$(VERSION)'

%.tar.gz: %          ;tar czf $*.tar.gz -C $* .
%-$(GOOS)-$(GOARCH): $(*D) ;$(GOBUILD) $(GOARGS) -o $@ ./$(*D)

.PHONY: docker-build-root docker-build-%
docker-build-root: ;docker build -t $(REGISTRY)$(OWNER)/$(REPO):$(VERSION) ./
docker-build-%:    ;docker build -t $(REGISTRY)$(OWNER)/$(REPO)-$*:$(VERSION) ./$*

.PHONY: docker-push-root docker-push-%
docker-push-root: docker-build-root ;docker push $(REGISTRY)$(OWNER)/$(REPO):$(VERSION)
docker-push-%:    docker-build-%    ;docker push $(REGISTRY)$(OWNER)/$(REPO)-$*:$(VERSION)

###############################################################################
# github-release - upload a binary release to github releases
#
# requirements:
# - the checked out revision be a pushed tag
# - a github api token ($GITHUB_TOKEN)
###############################################################################
GH_RELEASE := $(GOPATH)/bin/github-release
$(GH_RELEASE): ; go get github.com/aktau/github-release

.PHONY: create-gh-release gh-release-%
create-gh-release: $(GH_RELEASE) tag clean-repo gh-token
	@echo Creating Github Release
	$(GH_RELEASE) release --user $(OWNER) --repo $(REPO) --tag $(VERSION)

gh-release-%: $(GH_RELEASE) tag clean-repo gh-token create-gh-release
	@echo Uploading Release Artifact $* to Github
	$(GH_RELEASE) upload --user $(OWNER) --repo $(REPO) --tag $(VERSION) \
		--name $* --file $*

###############################################################################
.PHONY: gh-token
gh-token:
ifndef GITHUB_TOKEN
	$(error $GITHUB_TOKEN not set)
endif

###############################################################################
# utility
###############################################################################
.PHONY: tag clean-repo
tag:
	@echo Ensuring checkout is a tag.
	@git describe --tags --exact-match HEAD > /dev/null

clean-repo:
	@echo Ensuring repository is clean.
	@git diff --exit-code > /dev/null
	@git diff --cached --exit-code > /dev/null

###############################################################################
.DEFAULT_GOAL := info
info:
	@echo project: $(PROJECT)
	@echo version: $(VERSION)
