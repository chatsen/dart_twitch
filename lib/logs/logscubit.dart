import 'package:bloc/bloc.dart';

import 'logevent.dart';

class LogsCubit extends Cubit<List<LogEvent>> {
  LogsCubit() : super([]);

  void add(LogEvent log) => emit([...state, log]);
}
