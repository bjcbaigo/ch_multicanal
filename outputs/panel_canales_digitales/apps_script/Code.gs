const PROP_TOKEN = "CHEMES_CANALES_TOKEN";
const PROP_FILE_ID = "CHEMES_CANALES_CSV_FILE_ID";
const CSV_FILE_NAME = "canales_articulos_publicados.csv";

function doGet(e) {
  try {
    const csv = readCsv_();
    const callback = e && e.parameter ? e.parameter.callback : "";
    if (callback) {
      return ContentService
        .createTextOutput(`${callback}(${JSON.stringify({ ok: true, csv })});`)
        .setMimeType(ContentService.MimeType.JAVASCRIPT);
    }
    return ContentService
      .createTextOutput(csv)
      .setMimeType(ContentService.MimeType.CSV);
  } catch (error) {
    return jsonResponse_({ ok: false, error: String(error && error.message ? error.message : error) });
  }
}

function doPost(e) {
  try {
    assertToken_(e);
    const csv = e && e.postData ? e.postData.contents : "";
    if (!csv || csv.indexOf(";") < 0) {
      throw new Error("CSV vacio o invalido.");
    }
    const file = saveCsv_(csv);
    return jsonResponse_({
      ok: true,
      fileId: file.getId(),
      name: file.getName(),
      updatedAt: new Date().toISOString(),
      bytes: csv.length
    });
  } catch (error) {
    return jsonResponse_({ ok: false, error: String(error && error.message ? error.message : error) });
  }
}

function saveCsv_(csv) {
  const props = PropertiesService.getScriptProperties();
  const fileId = props.getProperty(PROP_FILE_ID);
  if (fileId) {
    const file = DriveApp.getFileById(fileId);
    file.setContent(csv);
    return file;
  }
  const file = DriveApp.createFile(CSV_FILE_NAME, csv, MimeType.CSV);
  props.setProperty(PROP_FILE_ID, file.getId());
  return file;
}

function readCsv_() {
  const fileId = PropertiesService.getScriptProperties().getProperty(PROP_FILE_ID);
  if (!fileId) {
    throw new Error("Todavia no hay CSV publicado.");
  }
  return DriveApp.getFileById(fileId).getBlob().getDataAsString("UTF-8");
}

function assertToken_(e) {
  const expected = PropertiesService.getScriptProperties().getProperty(PROP_TOKEN);
  if (!expected) {
    throw new Error(`Falta configurar Script Property ${PROP_TOKEN}.`);
  }
  const received = e && e.parameter ? e.parameter.token : "";
  if (received !== expected) {
    throw new Error("Token invalido.");
  }
}

function jsonResponse_(payload) {
  return ContentService
    .createTextOutput(JSON.stringify(payload))
    .setMimeType(ContentService.MimeType.JSON);
}
