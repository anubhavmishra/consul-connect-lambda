BUILD_ID := $(shell git rev-parse --short HEAD 2>/dev/null || echo no-commit-id)

.DEFAULT_GOAL := help
help: ## Show available targets
	@cat Makefile* | grep -E '^[a-zA-Z_-]+:.*?## .*$$' | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

clean: ## Clean the project
	rm -rf ./build
	mkdir ./build

deps: ## Download dependencies
	go get .

build-service: ## Build the project
	mkdir -p ./build/linux/amd64
	GOOS=linux GOARCH=amd64 go build -v -o ./build/linux/amd64/consul-connect-lambda .
	cd ./build/linux/amd64/ && zip consul-connect-lambda.zip consul-connect-lambda

deps-test:
	go get -t

test: ## Run tests, coverage reports, and clean (coverage taints the compiled code)
	go test -v .

run: ## Build and run the project
	mkdir -p ./build
	go build -o ./build/consul-connect-lambda && ./build/consul-connect-lambda