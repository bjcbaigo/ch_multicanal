import argparse
import base64
import csv
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


def auth_header(api_key: str) -> dict:
    token = base64.b64encode(f"{api_key}:".encode("ascii")).decode("ascii")
    return {"Authorization": f"Basic {token}", "User-Agent": "CHEMES-ImageExport/1.0"}


def request_bytes(url: str, headers: dict, retries: int) -> bytes:
    last_error = None
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=60) as response:
                return response.read()
        except Exception as exc:
            last_error = exc
            if attempt < retries:
                time.sleep(min(10, attempt * 2))
    raise last_error


def request_xml(url: str, headers: dict, retries: int) -> ET.Element:
    data = request_bytes(url, headers, retries)
    return ET.fromstring(data)


def text(node) -> str:
    if node is None or node.text is None:
        return ""
    return node.text.strip()


def safe_filename(value: str) -> str:
    value = value.strip()
    value = re.sub(r'[<>:"/\\|?*\x00-\x1f]', "_", value)
    value = re.sub(r"\s+", " ", value)
    return value


def join_url(base: str, path: str) -> str:
    return base.rstrip("/") + "/" + path.lstrip("/")


def public_image_url(shop_url: str, image_id: str) -> str:
    digits = "/".join(image_id)
    return join_url(shop_url, f"/img/p/{digits}/{image_id}.jpg")


def product_rows(root: ET.Element):
    products = root.find("products")
    if products is None:
        return []
    return list(products.findall("product"))


def image_ids(product: ET.Element):
    ids = []
    associations = product.find("associations")
    if associations is not None:
      images = associations.find("images")
      if images is not None:
          for image in images.findall("image"):
              value = text(image.find("id"))
              if value:
                  ids.append(value)
    if not ids:
        default_id = text(product.find("id_default_image"))
        if default_id:
            ids.append(default_id)
    return ids


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--shop-url", default="https://chemesweb.com.ar")
    parser.add_argument("--api-key-file", default=r"\\10.10.10.109\E$\Tareas\ticketera\.config\prestashop-api-key.txt")
    parser.add_argument("--output-dir", default="prestashop_imagenes")
    parser.add_argument("--page-size", type=int, default=50)
    parser.add_argument("--max-products", type=int, default=0)
    parser.add_argument("--retries", type=int, default=5)
    args = parser.parse_args()

    api_key = Path(args.api_key_file).read_text(encoding="utf-8").strip()
    headers = auth_header(api_key)
    output_dir = Path(args.output_dir).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    manifest = []
    processed = 0
    downloaded = 0
    skipped = 0
    without_sku = 0
    without_image = 0
    errors = 0
    offset = 0

    while True:
        if args.max_products and processed >= args.max_products:
            break
        query = urllib.parse.urlencode({
            "display": "full",
            "sort": "[id_ASC]",
            "limit": f"{offset},{args.page_size}",
        })
        url = join_url(args.shop_url, f"/api/products?{query}")
        root = request_xml(url, headers, args.retries)
        batch = product_rows(root)
        if not batch:
            break

        for product in batch:
            if args.max_products and processed >= args.max_products:
                break
            product_id = text(product.find("id"))
            sku = safe_filename(text(product.find("reference")))
            processed += 1

            if not sku:
                without_sku += 1
                manifest.append([product_id, "", "", "", "SIN_SKU"])
                continue

            ids = image_ids(product)
            if not ids:
                without_image += 1
                manifest.append([product_id, sku, "", "", "SIN_IMAGEN"])
                continue

            for index, image_id in enumerate(ids):
                suffix = "" if index == 0 else f"_{index + 1}"
                filename = f"{sku}{suffix}.jpg"
                path = output_dir / filename
                if path.exists() and path.stat().st_size > 0:
                    skipped += 1
                    status = "YA_EXISTE"
                else:
                    try:
                        data = request_bytes(public_image_url(args.shop_url, image_id), {}, args.retries)
                        path.write_bytes(data)
                        downloaded += 1
                        status = "OK"
                    except Exception as exc:
                        errors += 1
                        status = f"ERROR_DESCARGA: {exc}"
                manifest.append([product_id, sku, image_id, filename, status])

        offset += args.page_size
        print(f"Procesados: {processed} | Nuevas: {downloaded} | Existentes: {skipped} | Errores: {errors} | Offset: {offset}", flush=True)

        if len(batch) < args.page_size:
            break

    manifest_path = output_dir / "_manifest.csv"
    with manifest_path.open("w", newline="", encoding="utf-8-sig") as fh:
        writer = csv.writer(fh, delimiter=";")
        writer.writerow(["ProductId", "SKU", "ImageId", "FileName", "Status"])
        writer.writerows(manifest)

    print(f"OK carpeta: {output_dir}")
    print(f"Manifest: {manifest_path}")
    print(f"Productos procesados: {processed}")
    print(f"Imagenes nuevas: {downloaded}")
    print(f"Imagenes existentes: {skipped}")
    print(f"Sin SKU: {without_sku}")
    print(f"Sin imagen: {without_image}")
    print(f"Errores: {errors}")
    return 0 if errors == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
