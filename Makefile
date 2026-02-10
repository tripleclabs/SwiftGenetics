.PHONY: test coverage clean

test:
	swift test

coverage:
	swift test --enable-code-coverage
	bash scripts/generate_coverage.sh
	open coverage_report/index.html

clean:
	rm -rf .build
	rm -rf coverage_report
