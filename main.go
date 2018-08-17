package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/hashicorp/consul/api"
	"github.com/hashicorp/consul/connect"
)

const serviceName = "consul-connect-lambda"

var (
	requestServiceName = os.Getenv("REQUEST_SERVICE_NAME")
	consulAddr         = os.Getenv("CONSUL_ADDRESS")
)

// Handler function calls a HTTP service using Consul Connect native integration
func Handler() (string, error) {

	// Validate environment flags
	if consulAddr == "" {
		consulAddr = "localhost:8500"
	}

	if requestServiceName == "" {
		requestServiceName = "web.service.consul"
	}

	config := api.DefaultConfig()
	config.Address = fmt.Sprintf("http://%s", consulAddr)

	log.Println("Consul configuration address:", config.Address)

	consulClient, err := api.NewClient(config)
	if err != nil {
		return "", fmt.Errorf("unable to create consul client: %v", err)
	}

	log.Println("Created consul client.")

	// Create an instance representing this service. "consul-connect-lambda" is the
	// name of _this_ service. The service should be cleaned up via Close.
	svc, err := connect.NewService(serviceName, consulClient)
	if err != nil {
		return "", fmt.Errorf("unable to create a new consul connect service: %v", err)
	}
	defer svc.Close()

	log.Println("Created consul connect service.")

	t := &http.Transport{
		DialTLS: svc.HTTPDialTLS,
	}

	httpClient := &http.Client{
		Transport: t,
	}

	//httpClient := svc.HTTPClient()
	resp, err := httpClient.Get(fmt.Sprintf("https://%s/", requestServiceName))
	if err != nil {
		return "", fmt.Errorf("something went wrong: %v", err.Error())
	}

	body, _ := ioutil.ReadAll(resp.Body)

	// Respond with reponse body of the request above
	return string(body[:]), nil
}

func main() {
	lambda.Start(Handler)
}
