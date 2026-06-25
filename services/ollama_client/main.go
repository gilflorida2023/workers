package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

type OllamaClient struct {
	httpClient *http.Client
}

type GenerateRequest struct {
	Model   string `json:"model"`
	Prompt  string `json:"prompt"`
	Format  string `json:"format,omitempty"`
	Stream  bool   `json:"stream"`
	Options map[string]interface{} `json:"options,omitempty"`
}

type GenerateResponse struct {
	Response string `json:"response"`
	Done     bool   `json:"done"`
}

func NewOllamaClient(timeout time.Duration) *OllamaClient {
	return &OllamaClient{
		httpClient: &http.Client{Timeout: timeout},
	}
}

func (c *OllamaClient) Call(ctx context.Context, host, model, prompt string, formatJSON bool) (string, error) {
	url := fmt.Sprintf("http://%s:11434/api/generate", host)
	
	reqBody := GenerateRequest{
		Model:  model,
		Prompt: prompt,
		Stream: false,
	}
	if formatJSON {
		reqBody.Format = "json"
	}
	
	jsonBody, err := json.Marshal(reqBody)
	if err != nil {
		return "", err
	}
	
	req, err := http.NewRequestWithContext(ctx, "POST", url, bytes.NewBuffer(jsonBody))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")
	
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	
	var genResp GenerateResponse
	if err := json.NewDecoder(resp.Body).Decode(&genResp); err != nil {
		return "", err
	}
	
	return genResp.Response, nil
}

func main() {}