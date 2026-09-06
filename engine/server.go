package engine

import (
	"encoding/json"
	"net/http"
)

const UIHtml = `
<!DOCTYPE html>
<html>
<head>
    <title>Anant Abhyaas Ultra - Control Hub</title>
    <style>
        body { font-family: sans-serif; background: #0f172a; color: #f8fafc; padding: 30px; }
        .container { max-width: 700px; margin: auto; background: #1e293b; padding: 30px; border-radius: 12px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        h2 { color: #38bdf8; margin-top: 0; }
        .input-group { margin-bottom: 15px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; color: #cbd5e1; }
        input { width: 100%; padding: 12px; border-radius: 6px; border: 1px solid #475569; background: #0f172a; color: #fff; box-sizing: border-box; font-size: 14px; }
        .button-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 20px; }
        button { padding: 12px; border-radius: 6px; border: none; font-size: 15px; font-weight: bold; cursor: pointer; transition: 0.2s; }
        .btn-clone { background: #3b82f6; color: white; }
        .btn-audit { background: #8b5cf6; color: white; }
        .btn-sandbox { background: #f59e0b; color: white; }
        .btn-approve { background: #10b981; color: white; grid-column: span 2; }
        button:hover { opacity: 0.9; }
        #res { background: #020617; padding: 15px; margin-top: 20px; border-radius: 6px; font-family: monospace; color: #38bdf8; white-space: pre-wrap; max-height: 250px; overflow-y: auto; border: 1px solid #1e293b; }
    </style>
</head>
<body>
    <div class="container">
        <h2>Anant Abhyaas Ultra</h2>
        <p>हर स्टेप के लिए डेडिकेटेड बटन। गिटहब लिंक डालो और कंट्रोल अपने हाथ में लो।</p>
        
        <div class="input-group">
            <label>Project Name</label>
            <input type="text" id="pName" placeholder="e.g., student_portal" />
        </div>
        <div class="input-group">
            <label>GitHub Repository URL</label>
            <input type="text" id="repo" placeholder="https://github.com/user/repo.git" />
        </div>
        <div class="input-group">
            <label>Version Tag</label>
            <input type="text" id="ver" value="1.0.0" />
        </div>

        <div class="button-grid">
            <button class="btn-clone" onclick="executeStep('clone')">1. Add & Clone Repo</button>
            <button class="btn-audit" onclick="executeStep('audit')">2. Logic Audit & Scan</button>
            <button class="btn-sandbox" onclick="executeStep('sandbox')">3. Sandbox Live Demo</button>
            <button class="btn-approve" onclick="executeStep('approve')">4. Admin Approve & APK</button>
        </div>

        <div id="res">System ready. Select a button to begin...</div>
    </div>

    <script>
        async function executeStep(actionType) {
            const name = document.getElementById('pName').value;
            const repo = document.getElementById('repo').value;
            const ver = document.getElementById('ver').value;
            const res = document.getElementById('res');

            if(!name || !repo) {
                alert("Project Name aur GitHub Repo URL daalना अनिवार्य है!");
                return;
            }

            res.innerText = "Executing step: [" + actionType.toUpperCase() + "]... Please wait.";

            try {
                const response = await fetch('/api/run', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({project_name: name, repo_url: repo, version: ver, action: actionType})
                });
                const data = await response.json();
                
                if(data.status === "success") {
                    res.innerHTML = "✅ <b>Success (" + actionType.toUpperCase() + "):</b><br>" + data.message + 
                                    (data.download_url ? "<br><br><a href='"+data.download_url+"' style='color:#34d399; font-size:16px;' target='_blank'><b>📥 Direct Download APK Here</b></a>" : "");
                } else if(data.status === "error") {
                    res.innerText = "❌ Error: " + data.message;
                } else {
                    res.innerText = "ℹ️ Result:\n" + JSON.stringify(data, null, 2);
                }
            } catch(err) {
                res.innerText = "❌ Network Error: " + err.message;
            }
        }
    </script>
</body>
</html>
`

type Payload struct {
	ProjectName string `json:"project_name"`
	RepoURL     string `json:"repo_url"`
	Version     string `json:"version"`
	Action      string `json:"action"`
}

func StartServer() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		w.Write([]byte(UIHtml))
	})

	http.HandleFunc("/api/run", func(w http.ResponseWriter, r *http.Request) {
		var p Payload
		r.Body = http.MaxBytesReader(w, r.Body, 1048576)
		if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
			json.NewEncoder(w.Encode(map[string]string{"status": "error", "message": err.Error()}))
			return
		}

		result := RunPipeline(BuildJob{
			ProjectName: p.ProjectName,
			RepoURL:     p.RepoURL,
			Version:     p.Version,
		}, p.Action)

		json.NewEncoder(w.Encode(result))
	})

	http.Handle("/downloads/", http.StripPrefix("/downloads/", http.FileServer(http.Dir("./public_downloads"))))
	http.ListenAndServe(":8080", nil)
}

