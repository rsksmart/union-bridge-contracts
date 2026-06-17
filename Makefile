.PHONY: fmt-check
fmt-check:
	forge fmt --check

.PHONY: lint
lint:
	forge lint src script test # TODO add -D option when foundry version is >= 1.4.0
