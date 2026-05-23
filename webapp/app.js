const CONFIDENCE_THRESHOLD = 0.6;
const CONFIDENCE_HIGH = 0.85;

const apiHint = document.getElementById("apiHint");
const fileInput = document.getElementById("fileInput");
const dropZone = document.getElementById("dropZone");
const previewBlock = document.getElementById("previewBlock");
const preview = document.getElementById("preview");
const fileMeta = document.getElementById("fileMeta");
const btnClear = document.getElementById("btnClear");
const btnPredict = document.getElementById("btnPredict");
const results = document.getElementById("results");
const loading = document.getElementById("loading");
const errorEl = document.getElementById("error");

let selectedFile = null;
let previewUrl = null;

const apiBase =
  window.API_URL && !String(window.API_URL).includes("PASTE_")
    ? window.API_URL.replace(/\/$/, "")
    : "";

if (!apiBase) {
  apiHint.textContent =
    "Configura window.API_URL en config.js (URL de la API en EC2, puerto 8000).";
  showError(
    "Falta la URL de la API. Edita webapp/config.js con la IP pública de tu instancia EC2."
  );
}

function cropFromClass(classId) {
  return (classId || "").split("___")[0];
}

function formatFileSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(1)} MB`;
}

function hasMixedCrops(predictions) {
  return new Set(predictions.map((p) => cropFromClass(p.class))).size >= 2;
}

function getConfidenceState(confidence, predictions) {
  if (confidence < CONFIDENCE_THRESHOLD || hasMixedCrops(predictions)) {
    return "low";
  }
  if (confidence < CONFIDENCE_HIGH) {
    return "medium";
  }
  return "high";
}

function setFile(file) {
  if (previewUrl) {
    URL.revokeObjectURL(previewUrl);
    previewUrl = null;
  }
  selectedFile = file;
  errorEl.classList.add("hidden");
  results.classList.add("hidden");

  if (!file) {
    btnPredict.disabled = true;
    previewBlock.classList.add("hidden");
    dropZone.classList.remove("has-file");
    document.body.classList.remove("has-image");
    fileInput.value = "";
    return;
  }

  btnPredict.disabled = !apiBase;
  previewBlock.classList.remove("hidden");
  dropZone.classList.add("has-file");
  document.body.classList.add("has-image");

  preview.innerHTML = "";
  previewUrl = URL.createObjectURL(file);
  const img = document.createElement("img");
  img.src = previewUrl;
  img.alt = "Vista previa de la hoja";
  preview.appendChild(img);

  fileMeta.textContent = `${file.name} · ${formatFileSize(file.size)}`;
}

fileInput.addEventListener("change", () => {
  setFile(fileInput.files[0] || null);
});

btnClear.addEventListener("click", () => {
  setFile(null);
});

dropZone.addEventListener("click", (e) => {
  if (e.target === fileInput || e.target.closest("label")) return;
  fileInput.click();
});

dropZone.addEventListener("keydown", (e) => {
  if (e.key === "Enter" || e.key === " ") {
    e.preventDefault();
    fileInput.click();
  }
});

dropZone.addEventListener("dragover", (e) => {
  e.preventDefault();
  dropZone.classList.add("drag-over");
});

dropZone.addEventListener("dragleave", () => {
  dropZone.classList.remove("drag-over");
});

dropZone.addEventListener("drop", (e) => {
  e.preventDefault();
  dropZone.classList.remove("drag-over");
  const file = e.dataTransfer.files[0];
  if (file && file.type.startsWith("image/")) {
    setFile(file);
  }
});

btnPredict.addEventListener("click", () => {
  if (!selectedFile || !apiBase) return;
  predictViaApi();
});

async function predictViaApi() {
  const form = new FormData();
  form.append("file", selectedFile);

  loading.classList.remove("hidden");
  results.classList.add("hidden");
  errorEl.classList.add("hidden");
  btnPredict.disabled = true;

  try {
    const res = await fetch(`${apiBase}/predict`, { method: "POST", body: form });
    const data = await res.json();
    if (!res.ok) throw new Error(data.detail || res.statusText);

    render(getConfidenceState(data.confidence, data.predictions), data);
  } catch (err) {
    showError(err.message);
  } finally {
    loading.classList.add("hidden");
    btnPredict.disabled = false;
  }
}

function render(state, data) {
  results.classList.remove("hidden");
  const top = data.predictions[0];
  const pct = (top.confidence * 100).toFixed(1);
  const pctNum = parseFloat(pct);
  const altHeading =
    state === "low" ? "Hipótesis (baja certeza)" : "Otras posibilidades";

  let html = '<article class="result-card">';

  if (state === "low") {
    html += `
      <div class="alert-low" role="alert">
        <svg width="22" height="22" viewBox="0 0 24 24" aria-hidden="true">
          <path fill="currentColor" d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-2h2v2zm0-4h-2V7h2v6z"/>
        </svg>
        <p>Ojoverde no pudo identificar la hoja con suficiente certeza (${pct}%). Probablemente la imagen no corresponde a uno de los 14 cultivos del modelo, o la foto dificulta el análisis.</p>
      </div>
      <p class="hypothesis-label">Hipótesis (baja certeza)</p>`;
  }

  if (state === "high") {
    html += '<span class="badge badge-high">Alta confianza</span>';
  } else if (state === "medium") {
    html +=
      '<span class="badge badge-medium">Confianza moderada — verifica con otra foto si es posible</span>';
  } else {
    html += '<span class="badge badge-low">Baja certeza</span>';
  }

  html += `<h2 class="result-title">${top.display_name}</h2>`;

  html += `
    <div class="confidence-block">
      <div class="confidence-value state-${state}">${pct}%</div>
      <div class="confidence-bar-wrap" aria-hidden="true">
        <div class="confidence-threshold-mark" title="Umbral 60%"></div>
        <span class="confidence-threshold-label">60%</span>
        <div class="confidence-bar-fill state-${state}" style="width:${Math.min(pctNum, 100)}%"></div>
      </div>
    </div>`;

  html += `<div class="alt-list"><h3>${altHeading}</h3>`;
  for (const p of data.predictions) {
    const pPct = (p.confidence * 100).toFixed(1);
    html += `
      <li class="alt-item">
        <span>${p.display_name}</span>
        <span class="alt-pct">${pPct}%</span>
        <div class="alt-bar"><div class="alt-bar-fill" style="width:${pPct}%"></div></div>
      </li>`;
  }
  html += "</div>";

  if (data.s3_key) {
    html += `<p class="meta">Imagen en S3: <code>${data.s3_key}</code></p>`;
  }
  if (data.prediction_id) {
    html += `<p class="meta">Registro en PostgreSQL: #${data.prediction_id}</p>`;
  }
  if (data.s3_warning || data.db_warning) {
    html += `<p class="disclaimer">${data.s3_warning || data.db_warning}</p>`;
  }

  html += "</article>";
  results.innerHTML = html;
}

function showError(msg) {
  errorEl.textContent = msg;
  errorEl.classList.remove("hidden");
}
