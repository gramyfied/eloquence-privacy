import '../../repositories/auth_repository.dart';
import '../../entities/user.dart';

class SignUpUseCase {
  final AuthRepository _authRepository;

  SignUpUseCase(this._authRepository);

  Future<User> execute(String email, String password) {
    return _authRepository.signUpWithEmailAndPassword(email, password);
  }
}
