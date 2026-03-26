.PHONY: integration integration-noclean

integration:
	bash tests/integration/ci_run.sh

integration-noclean:
	bash tests/integration/ci_run.sh --skip-teardown
