import localUnitTest from './LocalUnit.test';
import numberParseTest from './NumberParse.test';
import mergeServiceTest from './MergeService.test';
import csvServiceTest from './CsvService.test';
import importLogicTest from './ImportLogic.test';

export default function testsuite() {
  localUnitTest();
  numberParseTest();
  mergeServiceTest();
  csvServiceTest();
  importLogicTest();
}
