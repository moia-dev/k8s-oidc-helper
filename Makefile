SHELL := /bin/bash

GITHUB_OWNER         = moia-dev
GITHUB_REPOSITORY    = k8s-oidc-helper

# The destination for binaries
BUILD_DIR = build

# The name of the executable (default is current directory name)
TARGET := $(shell echo $${PWD\#\#*/})
.DEFAULT_GOAL: $(TARGET)

# These will be provided to the target
VERSION :=0.2.0
BUILD := `git rev-parse HEAD`

# Use linker flags to provide version/build settings to the target
LDFLAGS=-ldflags "-X=main.Version=$(VERSION) -X=main.Build=$(BUILD)"

# go source files, ignore vendor directory
SRC = $(shell find . -type f -name '*.go' -not -path "./vendor/*")

.PHONY: all build clean install uninstall fmt simplify check run

all: check compile

$(TARGET): $(SRC)
	@go build $(LDFLAGS) -o $(TARGET)

.PHONY: release
release: guard-VERSION guard-GITHUB_TOKEN compile
	github-release info --user $(GITHUB_OWNER) --repo $(GITHUB_REPOSITORY)
	github-release release --user $(GITHUB_OWNER) --repo $(GITHUB_REPOSITORY) --tag v$(VERSION) --name v$(VERSION)
	for f in build/linux/*; do github-release upload --user $(GITHUB_OWNER) --repo $(GITHUB_REPOSITORY) --tag v$(VERSION) --name linux/`basename $${f}` --file $${f}; done
	for f in build/darwin/*; do github-release upload --user $(GITHUB_OWNER) --repo $(GITHUB_REPOSITORY) --tag v$(VERSION) --name darwin/`basename $${f}` --file $${f}; done
	github-release edit --user $(GITHUB_OWNER) --repo $(GITHUB_REPOSITORY) --tag v$(VERSION) --name v$(VERSION) --description v$(VERSION)

compile: check goxcompile

goxcompile: export CGO_ENABLED=0
goxcompile: dependencies
	gox -arch amd64 -os darwin -os linux -os windows -output "$(BUILD_DIR)/{{.OS}}/$(NAME)/${TARGET}" .

clean:
	@rm -f $(TARGET)
	@rm -rf $(BUILD_DIR)

install: dependencies
	@go install $(LDFLAGS)

uninstall: clean
	@rm -f $$(which ${TARGET})

fmt:
	@gofmt -l -w $(SRC)

simplify:
	@gofmt -s -l -w $(SRC)

check: dependencies
	@test -z $(shell gofmt -l *.go | tee /dev/stderr) || echo "[WARN] Fix formatting issues with 'make fmt'"
	@for d in $$(go list ./... | grep -v /vendor/); do golint $${d}; done
	@go tool vet ${SRC}

run: install
	@$(TARGET)

dependencies:
	go get github.com/mitchellh/gox
	go get github.com/jstemmer/go-junit-report
	go get github.com/golang/lint/golint
	git submodule update --init --recursive

guard-%:
	@ if [ "${${*}}" = "" ]; then \
             echo "Environment variable $* not set"; \
             exit 1; \
        fi
