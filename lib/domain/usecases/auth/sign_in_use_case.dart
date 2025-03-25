import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';

class SignInUseCase {
  final AuthRepository _authRepository;

  SignInUseCase(this._authRepository);

  Future<User> execute(String email, String password) {
    return _authRepository.signInWithEmailAndPassword(email, password);
  }
}
