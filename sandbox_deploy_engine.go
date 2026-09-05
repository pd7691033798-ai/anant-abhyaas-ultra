package main

import (
	"encoding/json"
	"net/http"
	"sync"
)

var (
	apkDeliveryLock sync.Mutex
	activeApkUrl    = "https://drive.google.com/uc?export=download&id=1qjFBSJ9T_mVo1U7Du1mSXwrGlQFpf1MI"
)

// 1. सैंडबॉक्स यूआई स्कीमा
func GetSandboxManifestHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	manifest := map[string]interface{}{
		"status": "READY",
		"user_ui": map[string]interface{}{
			"title":       "उपभोक्ता ऐप लाइव डेमो",
			"theme_color": "#1E88E5",
			"components":  []string{"HeaderBanner", "TaskCardList", "ScanFloatingButton"},
		},
		"admin_ui": map[string]interface{}{
			"title":       "एडमिन कंट्रोल डेमो",
			"theme_color": "#263238",
			"components":  []string{"MetricsOverview", "LiveWebhookLog", "ApprovalButton"},
		},
	}
	json.NewEncoder(w).Encode(manifest)
}

// 2. एडमिन अप्रूवल और फ़ाइनल 1-क्लिक APK
func ApproveAndGenerateApkHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method Not Allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	apkDeliveryLock.Lock()
	url := activeApkUrl
	apkDeliveryLock.Unlock()

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":           "SUCCESS",
		"message":          "एडमिन सत्यापन पूर्ण। फ़ाइनल प्रोडक्शन APK तैयार है।",
		"apk_download_url": url,
	})
}

// 3. Codemagic पोस्ट-बिल्ड ऑटो-रिसीवर
func CodemagicWebhookReceiverHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var payload struct {
		Status string `json:"status"`
		ApkUrl string `json:"apk_url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&payload); err == nil && payload.ApkUrl != "" {
		apkDeliveryLock.Lock()
		activeApkUrl = payload.ApkUrl
		apkDeliveryLock.Unlock()
	}
	w.WriteHeader(http.StatusOK)
}

// 4. मुख्य सर्वर रूट्स रजिस्ट्रेशन (इसे main.go में कॉल करें)
func RegisterAllAutonomousRoutes() {
	http.HandleFunc("/api/github/repos", ListGitHubReposHandler)
	http.HandleFunc("/api/github/commit", CommitToRepoHandler)
	http.HandleFunc("/api/repo/inspect", InspectRepoLogicHandler)
	http.HandleFunc("/api/whatsapp/demo-chat", WhatsAppDemoChatHandler)
	http.HandleFunc("/api/sandbox/manifest", GetSandboxManifestHandler)
	http.HandleFunc("/api/sandbox/approve-build", ApproveAndGenerateApkHandler)
	http.HandleFunc("/api/codemagic/webhook", CodemagicWebhookReceiverHandler)
}
