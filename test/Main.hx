package;

import utest.Runner;
import utest.ui.Report;

class Main {
	static function main() {
		final runner = new Runner();
		runner.addCases(test.tests);
		Report.create(runner);
		runner.run();
	}
}
