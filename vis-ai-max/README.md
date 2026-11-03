# VIS AI MAX — GitHub Pages edition

Browser interface for VIS AI MAX, published as a static site.

## Open

After GitHub Pages publishes the commit:

- https://vis-os.com/vis-ai-max/
- Repository: https://github.com/tjhtjdddvdv-lgtm/VIS-OS2.COM/tree/main/vis-ai-max

## What works in the static edition

- Responsive chat interface.
- Local document library in the browser (IndexedDB).
- Import TXT, MD, JSON, JSONL and CSV.
- Text chunking and keyword-based retrieval.
- Search results with document and chunk references.
- Export the indexed text chunks as JSONL.
- Optional connection to a separately hosted VIS AI MAX API.

## Important architecture note

GitHub Pages serves static HTML, CSS and JavaScript only. It does not run Python, FastAPI, PyTorch, model training, or a persistent server-side database. Without an API URL configured, the chat performs retrieval over the user's browser-local documents; it is not a neural language model.

To use a real model, deploy the VIS AI MAX Python API separately, enable CORS for the Pages/custom domain, then set its base URL in **Settings**. The API should implement:

- `GET /api/status`
- `POST /api/chat` with JSON `{"message":"...","history":[]}`

Do not put private API keys or credentials in this public repository or static frontend.

## Storage

Imported documents remain in IndexedDB in the current browser profile. They are not uploaded to GitHub. Clearing browser data can remove this local library, so export important corpora regularly.
