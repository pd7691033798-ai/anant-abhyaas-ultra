package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"sync"
	"time"
)

// ==========================================
// 1. सर्वर-ड्रिवन UI और एक्शन डेटा मॉडल
// ==========================================

type UIComponent struct {
	Type       string            `json:"type"`       // "banner", "card", "button", "stats_card"
	Title      string            `json:"title"`
	Subtitle   string            `json:"subtitle,omitempty"`
	ActionKey  string            `json:"action_key,omitempty"` // "OPEN_WHATSAPP_SIM", "OPEN_CODE_PASTE"
	Properties map[string]string `json:"properties,omitempty"`
}

type DynamicScreenPayload struct {
	ScreenTitle string        `json:"screen_title"`
	Version     int           `json:"version"`
	UpdatedAt   string        `json:"updated_at"`
	Components  []UIComponent `json:"components"`
}

type ActionExecutionRequest struct {
	ActionKey string            `json:"action_key"`
	Payload   map[string]string `json:"payload,omitempty"`
}

var (
	uiLayoutLock sync.Mutex
	// सर्वर-ड्रिवन डिफ़ॉल्ट लेआउट
	currentScreenState = DynamicScreenPayload{
		ScreenTitle: "अनंत अभ्यास - सॉवरन स्टूडियो",
		Version:     1,
		UpdatedAt:   time.Now().Format("02 Jan 2006, 15:04:05"),
		Components: []UIComponent{
			{
				Type:     "banner",
				Title:    "🚀 ऑटोनोमस स्टूडियो इंजन सक्रिय है",
				Subtitle: "सर्वर-ड्रिवन UI एक्टिव है। स्क्रीन का लेआउट बिना APK बदले बदल सकता है।",
			},
			{
				Type:      "card",
				Title:     "🟢 WhatsApp बॉट टेस्ट रूम",
				Subtitle:  "लाइव चैट सिम्युलेटर खोलें और बॉट कमांड्स का परीक्षण करें।",
				ActionKey: "OPEN_WHATSAPP_SIM",
			},
			{
				Type:      "card",
				Title:     "⚡ स्वायत्त कोड कमिट (Direct Push)",
				Subtitle:  "कोड पेस्ट करें - इंजन खुद फाइल पहचानकर GitHub पर पुश कर देगा।",
				ActionKey: "OPEN_CODE_PASTE",
			},
		},
	}
)

// ==========================================
// 2. HTTP हैंडलर्स (DYNAMIC UI & ACTIONS)
// ==========================================

// 1. स्क्रीन का ताज़ा लेआउट देने वाला हैंडलर
func DynamicScreenLayoutHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	uiLayoutLock.Lock()
	defer uiLayoutLock.Unlock()

	currentScreenState.UpdatedAt = time.Now().Format("02 Jan 2006, 15:04:05")
	json.NewEncoder(w).Encode(currentScreenState)
}

// 2. एक्शन्स (WhatsApp Sim & Code Paste) को प्रोसेस करने वाला गेटवे
func DynamicActionExecutionHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var req ActionExecutionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid Action Request", http.StatusBadRequest)
		return
	}

	response := map[string]interface{}{
		"action_key": req.ActionKey,
		"status":     "ACTION_DISPATCHED",
	}

	switch req.ActionKey {
	case "OPEN_WHATSAPP_SIM":
		response["target_module"] = "WHATSAPP_LIVE_CHAT"
		response["endpoint"] = "/api/builder/universal-sim?platform=WHATSAPP"
		response["message"] = "WhatsApp लाइव सिम्युलेटर एक्टिवेट किया गया।"

	case "OPEN_CODE_PASTE":
		response["target_module"] = "DIRECT_CODE_COMMIT_SHEET"
		response["endpoint"] = "/api/builder/direct-commit"
		response["message"] = "स्वायत्त कोड कमिट शीट तैयार है।"

	default:
		response["status"] = "UNKNOWN_ACTION"
		response["message"] = fmt.Sprintf("एक्शन '%s' के लिए कोई रूट नहीं मिला।", req.ActionKey)
	}

	json.NewEncoder(w).Encode(response)
}

// 3. लेआउट को सर्वर साइड से अपडेट करने वाला एडमिन एंडपॉइंट (बिना APK बदले)
func UpdateDynamicLayoutHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	if r.Method != http.MethodPost {
		http.Error(w, "Method Not Allowed", http.StatusMethodNotAllowed)
		return
	}

	var newLayout DynamicScreenPayload
	if err := json.NewDecoder(r.Body).Decode(&newLayout); err != nil {
		http.Error(w, "Invalid Layout Schema", http.StatusBadRequest)
		return
	}

	uiLayoutLock.Lock()
	currentScreenState = newLayout
	currentScreenState.Version++
	currentScreenState.UpdatedAt = time.Now().Format("02 Jan 2006, 15:04:05")
	uiLayoutLock.Unlock()

	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":      "LAYOUT_UPDATED_SUCCESSFULLY",
		"new_version": currentScreenState.Version,
	})
}

// ==========================================
// 3. मुख्य सर्वर में केवल 1 लाइन का रजिस्ट्रेशन फ़ंक्शन
// ==========================================
func RegisterDynamicUIEngineRoutes() {
	http.HandleFunc("/api/ui/dynamic-screen", DynamicScreenLayoutHandler)
	http.HandleFunc("/api/ui/handle-action", DynamicActionExecutionHandler)
	http.HandleFunc("/api/ui/update-layout", UpdateDynamicLayoutHandler)
}
