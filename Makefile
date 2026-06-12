.PHONY: fmt lint

fmt-check:
	forge fmt --check

lint:
	forge lint src script test # TODO enable when foundry version is >= 1.4.0 -D notes
