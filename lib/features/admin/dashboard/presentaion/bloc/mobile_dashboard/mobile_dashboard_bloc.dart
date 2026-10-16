import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/errors/app_exceptions.dart';
import '../../../data/models/mobile_dashboard_response_model.dart';
import '../../../domain/usecases/get_mobile_dashboard_usecase.dart';

part 'mobile_dashboard_event.dart';
part 'mobile_dashboard_state.dart';

class MobileDashboardBloc
    extends Bloc<MobileDashboardEvent, MobileDashboardState> {
  final GetMobileDashboardUseCase getMobileDashboardUseCase;

  MobileDashboardBloc({required this.getMobileDashboardUseCase})
    : super(MobileDashboardInitial()) {
    on<GetMobileDashboardEvent>(_onGetDashboard);
  }

  Future<void> _onGetDashboard(
    GetMobileDashboardEvent event,
    Emitter<MobileDashboardState> emit,
  ) async {
    emit(MobileDashboardLoading());

    try {
      final result = await getMobileDashboardUseCase();

      emit(MobileDashboardLoaded(result));
    } on UnauthorizedException catch (e) {
      // Token deleted / expired -> page sends the user to sign in
      emit(MobileDashboardSessionExpired(e.message));
    } on AppException catch (e) {
      emit(MobileDashboardError(e.message));
    } catch (e) {
      emit(const MobileDashboardError('Failed to load dashboard data'));
    }
  }
}