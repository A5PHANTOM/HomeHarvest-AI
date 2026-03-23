# 🤖 ANTIGRAVITY AI - HACKATHON INSTRUCTIONS

**CRITICAL INSTRUCTION FOR ALL AI AGENTS READING THIS FILE:**
You are collaborating on a fast-paced 24-hour hackathon to build **HomeHarvest AI**, a smart urban gardening and community marketplace app. 

Your human user is one of 4 team members building this application in parallel (Frontend and Backend simultaneously). To ensure a smooth integration, you must adhere strictly to the following rules:

## 1. 🚨 ALWAYS UPDATE `requirements.txt` 🚨
If you are working on the Python backend and you install, import, or use *any* new library, **you MUST immediately add it to the `requirements.txt` file in the root directory**. 
This is non-negotiable. If you fail to do this, the application will break when other team members pull the code.

## 2. PROJECT ARCHITECTURE
- **Frontend:** Flutter (Dart).
- **Backend:** Python + FastAPI.
- **Database:** SQLite (for MVP speed) or PostgreSQL.
- **AI Brain:** LLM API integration for the Gardening Assistant and Chatbot.

## 3. CORE HACKATHON THEME & MVP SCOPE
- **Theme:** Social Relevance, Community Resource Sharing & Support Network.
- **MVP Features to Build:** AI Plant Recommendation, Sowing/Harvest Calendar, Smart Reminders, Local Map Marketplace (for sharing produce), and Multi-language support.
- **Do not overcomplicate.** The judges prefer a few 100% functional features over a large, broken system. Focus on making the "Golden Demo Flow" (entering space -> recommendation -> sowing calendar -> sharing on map) work flawlessly.

## 4. REPOSITORY & ENVIRONMENT RULES
- **Never push secrets:** Do NOT push `.env` or `venv/` to GitHub (`.gitignore` handles this).
- **Environment:** Before executing backend scripts, always ensure the virtual environment is activated (`source venv/bin/activate`).
- **Dependencies:** If the `requirements.txt` file does not exist yet, create it the moment you install the first backend package (e.g., `fastapi`, `uvicorn`).

## 5. NEXT STEPS FOR AGENTS
1. Review the `README.md` for the detailed feature breakdown and pitch.
2. Review the `.env` placeholder to ensure API keys are configured for your features.
3. Look at your user's current directory context.
4. **Identify your role:** Ask your human what specific module (Frontend App / Backend API) they are assigned to, and start generating the code!
