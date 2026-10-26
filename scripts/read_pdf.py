import json
import sys
import pymupdf

try:
    with pymupdf.open(sys.argv[1]) as doc:
        if doc.needs_pass:
            raise ValueError("PDF is password protected")
        index = max(0, min(int(sys.argv[2]) - 1, len(doc) - 1))
        text = doc[index].get_text(sort=True)
        result = {"page": index + 1, "pages": len(doc), "text": text}
    sys.stdout.buffer.write(json.dumps(result, ensure_ascii=False).encode("utf-8"))
except Exception as error:
    sys.stderr.write(str(error))
    sys.exit(1)
