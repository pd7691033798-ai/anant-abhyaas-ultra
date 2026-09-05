package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

type GitHubRepoItem struct {
	Name          string `json:"name"`
	FullName      string `json:"full_name"`
	HTMLURL       string `json:"html_url"`
	DefaultBranch string `json:"default_branch"`
}

// 1. GitHub से सभी रिपॉजिटरीज़ लाना
func ListGitHubReposHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	pat := os.Getenv("GITHUB_PAT")
	if pat == "" {
		http.Error(w, `{"error":"GITHUB_PAT environment variable not set"}`, http.StatusInternalServerError)
		return
	}

	req, _ := http.NewRequest("GET", "https://api.github.com/user/repos?per_page=100&sort=updated", nil)
	req.Header.Set("Authorization", "Bearer "+pat)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	client := &http.Client{}
	resp, err := client.Do(req)
	if err != nil || resp.StatusCode >= 400 {
		http.Error(w, `{"error":"GitHub repos fetch failed"}`, http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	body, _ := io.ReadAll(resp.Body)
	var repos []GitHubRepoItem
	_ = json.Unmarshal(body, &repos)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status": "SUCCESS",
		"repos":  repos,
	})
}

// 2. ऐप से सीधे GitHub पर कोड कमिट करना
func CommitToRepoHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method Not Allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Owner   string `json:"owner"`
		Repo    string `json:"repo"`
		Path    string `json:"path"`
		Content string `json:"content"`
		Message string `json:"message"`
		SHA     string `json:"sha"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	pat := os.Getenv("GITHUB_PAT")
	url := fmt.Sprintf("https://api.github.com/repos/%s/%s/contents/%s", req.Owner, req.Repo, req.Path)

	payload := map[string]interface{}{
		"message": req.Message,
		"content": req.Content,
	}
	if req.SHA != "" {
		payload["sha"] = req.SHA
	}
	pBytes, _ := json.Marshal(payload)

	ghReq, _ := http.NewRequest("PUT", url, bytes.NewBuffer(pBytes))
	ghReq.Header.Set("Authorization", "Bearer "+pat)
	ghReq.Header.Set("Content-Type", "application/json")

	client := &http.Client{}
	ghResp, err := client.Do(ghReq)
	if err != nil || ghResp.StatusCode >= 400 {
		http.Error(w, `{"error":"Commit push failed"}`, http.StatusBadGateway)
		return
	}
	defer ghResp.Body.Close()

	json.NewEncoder(w).Encode(map[string]string{
		"status":  "SUCCESS",
		"message": "बदलाव GitHub पर सफलतापूर्वक कमिट हो चुके हैं",
	})
}
