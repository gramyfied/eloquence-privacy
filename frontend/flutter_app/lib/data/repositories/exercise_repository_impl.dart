import 'package:dartz/dartz.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../core/error/failures.dart';
import '../../core/error/exceptions.dart';
import '../../core/utils/logger.dart';
import '../datasources/exercise_local_data_source.dart';
import '../datasources/exercise_remote_data_source.dart';
import '../models/exercise_model.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  final ExerciseLocalDataSource localDataSource;
  final ExerciseRemoteDataSource remoteDataSource;

  ExerciseRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, List<Exercise>>> getExercises() async {
    try {
      final remoteExercises = await remoteDataSource.getExercises();
      await localDataSource.cacheExercises(remoteExercises);
      return Right(remoteExercises.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      AppLogger.error('Failed to fetch exercises from server', e);
      try {
        final localExercises = await localDataSource.getLastExercises();
        return Right(localExercises.map((model) => model.toEntity()).toList());
      } on CacheException catch (e) {
        AppLogger.error('Failed to fetch exercises from cache', e);
        return Left(CacheFailure(message: e.message, code: e.code));
      } catch (e) {
        AppLogger.error('Unexpected error when fetching exercises from cache', e);
        return Left(CacheFailure(message: e.toString()));
      }
    } catch (e) {
      AppLogger.error('Unexpected error when fetching exercises', e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Exercise>> getExerciseById(String id) async {
    try {
      final exerciseModel = await remoteDataSource.getExerciseById(id);
      await localDataSource.cacheExercise(exerciseModel);
      return Right(exerciseModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error('Failed to fetch exercise from server', e);
      try {
        final localExercise = await localDataSource.getExerciseById(id);
        return Right(localExercise.toEntity());
      } on CacheException catch (e) {
        AppLogger.error('Failed to fetch exercise from cache', e);
        return Left(CacheFailure(message: e.message, code: e.code));
      } catch (e) {
        AppLogger.error('Unexpected error when fetching exercise from cache', e);
        return Left(CacheFailure(message: e.toString()));
      }
    } catch (e) {
      AppLogger.error('Unexpected error when fetching exercise', e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Exercise>> markExerciseAsCompleted(String id) async {
    try {
      final exerciseModel = await remoteDataSource.markExerciseAsCompleted(id);
      await localDataSource.cacheExercise(exerciseModel);
      return Right(exerciseModel.toEntity());
    } on ServerException catch (e) {
      AppLogger.error('Failed to mark exercise as completed on server', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      AppLogger.error('Unexpected error when marking exercise as completed', e);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Exercise>>> getRecommendedExercises() async {
    try {
      final recommendedExercises = await remoteDataSource.getRecommendedExercises();
      return Right(recommendedExercises.map((model) => model.toEntity()).toList());
    } on ServerException catch (e) {
      AppLogger.error('Failed to fetch recommended exercises', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      AppLogger.error('Unexpected error when fetching recommended exercises', e);
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
