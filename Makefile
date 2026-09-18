# Build the delivery document from its markdown source.
# The repository files are normative; this is a rendering for people who want
# one file rather than a tree.

DOC = docs/IDR_Properties_and_Acceptance_Criteria

.PHONY: doc check clean

doc:
	pandoc $(DOC).md -o $(DOC).docx --toc --toc-depth=2
	@echo "built $(DOC).docx"

check:
	@python3 -c "import yaml,re,sys; \
fx=yaml.safe_load(open('fixtures/idr.yaml')); \
d=set(re.findall(r'^## (IDR-P\d+)', open('properties/IDR-PROPERTIES.md').read(), re.M)); \
i={f['property'] for f in fx}; \
print(f'{len(d)} properties, {len(fx)} fixtures'); \
sys.exit(1) if d-i or i-d else print('properties and fixtures agree')"
	@for s in harness/*.sh; do bash -n $$s && echo "ok  $$s"; done
	@python3 -m py_compile harness/session_watch.py && echo "ok  harness/session_watch.py"

clean:
	rm -f $(DOC).docx
	rm -rf harness/__pycache__
