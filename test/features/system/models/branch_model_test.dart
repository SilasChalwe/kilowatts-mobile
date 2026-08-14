import 'package:flutter_test/flutter_test.dart';
import 'package:kilowatts_mobile/features/system/models/branch_model.dart';

void main() {
  test('uses installer-rated current as an estimate, not a measured fault', () {
    final branch = BranchModel.fromJson(const {
      'nodeMac': 'AA:BB:CC:DD:EE:FF',
      'relayPin': 4,
      'maximumCurrentAmps': 2.0,
      'maximumCurrentConfigured': true,
      'load': {
        'name': 'Pump',
        'nominalCurrentAmps': 2.2,
        'health': 'AVAILABLE',
      },
    });

    expect(branch.estimatedCurrentA, 2.2);
    expect(branch.status, BranchStatus.warning);
    expect(branch.status, isNot(BranchStatus.fault));
  });

  test('a relay-reported fault remains a fault regardless of its rating', () {
    final branch = BranchModel.fromJson(const {
      'maximumCurrentAmps': 10.0,
      'load': {
        'nominalCurrentAmps': 1.0,
        'health': 'FAULTED',
      },
    });

    expect(branch.status, BranchStatus.fault);
  });
}
