enum CommandStatus { pending, confirmed, failed }

/// The result of a command sent to Central (a load or system-config
/// change). The UI must not assume a tap changed physical hardware — it
/// waits for this outcome instead of optimistically updating state.
class CommandOutcome {
  const CommandOutcome._(this.status, this.message);

  const CommandOutcome.confirmed() : this._(CommandStatus.confirmed, null);
  const CommandOutcome.failed(String message)
    : this._(CommandStatus.failed, message);

  final CommandStatus status;
  final String? message;

  bool get isConfirmed => status == CommandStatus.confirmed;
}
