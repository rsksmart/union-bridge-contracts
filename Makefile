.PHONY: fmt lint

fmt-check:
	forge fmt --check

lint:
	forge lint src script test -D notes
