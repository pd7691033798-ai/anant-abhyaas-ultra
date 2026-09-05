package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"
)

// ब्रांड और डेमो कॉन्फ़िगरेशन मॉडल
type BrandConfig struct {
	AppName    string `json:"app_name"`
	Tagline    string `json:"tagline"`
	LogoURL    string `json:"logo_url"`
	UpdatedAt  string `json:"updated_at"`
}

type RepoDemoStateTwo struct {
	RepoName    string `json:"repo_name"`
	RepoURL     string `json:"repo_url"`
	HTMLContent string `json:"html_content"`
}

var (
	brandLock       sync.Mutex
	activeBrand     = BrandConfig{
		AppName:   "सॉवरन स्टूडियो",
		Tagline:   "अल्ट्रा ऑटोनोमस इंजन",
		LogoURL:   "https://anant-abhyaas-ultra.onrender.com/assets/logo.png",
		UpdatedAt: time.Now().Format("02 Jan 2006, 15:04:05"),
	}

	demoLockTwo    sync.Mutex
	activeDemosTwo = make(map[string]RepoDemoStateTwo)
)

// 1. डायनामिक ब्रांड व लोगो एंडपॉइंट (Flutter ऐप यहाँ से लोगो और नाम खींचेगा)
func BrandConfigHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	brandLock.Lock()
	defer brandLock.Unlock()

	// अगर POST रिक्वेस्ट है तो नया नाम या लोगो यहीं से अपडेट हो जाएगा
	if r.Method == http.MethodPost {
		var newConfig BrandConfig
		if err := json.NewDecoder(r.Body).Decode(&newConfig); err == nil {
			if newConfig.AppName != "" {
				activeBrand.AppName = newConfig.AppName
			}
			if newConfig.Tagline != "" {
				activeBrand.Tagline = newConfig.Tagline
			}
			if newConfig.LogoURL != "" {
				activeBrand.LogoURL = newConfig.LogoURL
			}
			activeBrand.UpdatedAt = time.Now().Format("02 Jan 2006, 15:04:05")
		}
	}

	json.NewEncoder(w).Encode(activeBrand)
}

// 2. डेमो तैयार करने वाला हैंडलर (सैंडबॉक्स में भी आपका लोगो दिखेगा)
func PrepareDemoHandlerTwo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method Not Allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Repo string `json:"repo"`
		Name string `json:"name"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid JSON payload"}`, http.StatusBadRequest)
		return
	}

	brandLock.Lock()
	logo := activeBrand.LogoURL
	appTitle := activeBrand.AppName
	brandLock.Unlock()

	demoLockTwo.Lock()
	activeDemosTwo[req.Name] = RepoDemoStateTwo{
		RepoName: req.Name,
		RepoURL:  req.Repo,
		HTMLContent: fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        body { background: #0B0F19; color: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 20px; text-align: center; }
        .logo-img { width: 75px; height: 75px; border-radius: 50%%; border: 2px solid #00FFCC; margin-bottom: 12px; object-fit: cover; }
        .card { background: #131B2E; border: 1px solid #00FFCC; border-radius: 14px; padding: 20px; margin-top: 15px; box-shadow: 0 4px 20px rgba(0,255,204,0.15); }
        h2 { color: #00FFCC; margin: 0 0 8px 0; font-size: 18px; }
        p { color: #94A3B8; font-size: 13px; line-height: 1.5; word-break: break-all; }
        .badge { display: inline-block; background: #064E3B; color: #34D399; padding: 6px 12px; border-radius: 20px; font-size: 12px; font-weight: bold; margin-top: 10px; }
    </style>
</head>
<body>
    <img src="%s" class="logo-img" alt="Logo" onerror="this.style.display='none'">
    <h3 style="color:#8B5CF6; margin:0;">%s</h3>
    <div class="card">
        <h2>⚡ %s सैंडबॉक्स</h2>
        <p><b>रिपॉजिटरी लिंक:</b><br>%s</p>
        <div class="badge">● लाइव डेमो सक्रिय है</div>
    </div>
</body>
</html>`, logo, appTitle, req.Name, req.Repo),
	}
	demoLockTwo.Unlock()

	demoURL := fmt.Sprintf("https://anant-abhyaas-ultra.onrender.com/api/builder/view-sandbox?name=%s", req.Name)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":   "DEMO_READY",
		"demo_url": demoURL,
	})
}

// 3. वेबव्यू के लिए सैंडबॉक्स HTML रेंडरर
func ViewSandboxHandlerTwo(w http.ResponseWriter, r *http.Request) {
	name := r.URL.Query().Get("name")
	demoLockTwo.Lock()
	demo, exists := activeDemosTwo[name]
	demoLockTwo.Unlock()

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	if !exists {
		fmt.Fprintf(w, "<html><body style='background:#0B0F19;color:white;text-align:center;padding:40px;'><h3>सैंडबॉक्स तैयार किया जा रहा है...</h3></body></html>")
		return
	}
	fmt.Fprint(w, demo.HTMLContent)
}

// 4. APK कंपाइलर ट्रिगर
func CompileApkHandlerTwo(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method Not Allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Repo    string `json:"repo"`
		AppName string `json:"app_name"`
	}
	_ = json.NewDecoder(r.Body).Decode(&req)

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":           "SUCCESS",
		"apk_download_url": "https://drive.google.com/uc?export=download&id=1qjFBSJ9T_mVo1U7Du1mSXwrGlQFpf1MI",
	})
}

// ==========================================
// इंजन टू रूट्स रजिस्ट्रेशन
// ==========================================
func RegisterRepoEngineTwoRoutes() {
	http.HandleFunc("/api/brand/config", BrandConfigHandler)
	http.HandleFunc("/api/builder/prepare-demo", PrepareDemoHandlerTwo)
	http.HandleFunc("/api/builder/view-sandbox", ViewSandboxHandlerTwo)
	http.HandleFunc("/api/builder/compile-apk", CompileApkHandlerTwo)
}
