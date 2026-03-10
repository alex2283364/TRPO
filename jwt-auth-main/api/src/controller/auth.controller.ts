import { Request, Response } from 'express';
import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import userService from '../services/user.service.ts';
import { SendMail } from '../services/Sendmail.ts';
import moment from 'moment';

// Генерация токенов
const generateAccessToken = (userId: number, email: string): string => {
  return jwt.sign(
    { id: userId, email },
    process.env.ACCESS_TOKEN_SECRET_KEY || 'default_access_key',
    { expiresIn: '30s' }
  );
};

const generateRefreshToken = (userId: number): string => {
  return jwt.sign(
    { id: userId },
    process.env.REFRESH_TOKEN_SECRET_KEY || 'default_refresh_key',
    { expiresIn: '2m' }
  );
};

// Регистрация
export const signup = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password, firstname, lastname, patronymic } = req.body;

    // Проверка существующего пользователя
    const existingUser = await userService.findByEmail(email);
    if (existingUser) {
      res.status(400).json({ message: 'Пользователь с таким email уже существует' });
      return;
    }

    // Хэширование пароля
    const hashedPassword = await bcrypt.hash(password, 10);

    // Создание пользователя
    const user = await userService.create(email, hashedPassword);

    // Генерация токенов
    const accessToken = generateAccessToken(user.id, user.email || '');
    const refreshToken = generateRefreshToken(user.id);

    // Сохранение refresh token (можно добавить в отдельную таблицу)
    // await prisma.refreshToken.create({ ... })

    res.status(201).json({
      message: 'Пользователь успешно зарегистрирован',
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        isActive: user.is_active
      }
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({ message: 'Ошибка сервера при регистрации' });
  }
};

// Вход
export const signin = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email, password } = req.body;

    // Поиск пользователя
    const user = await userService.findByEmail(email);
    if (!user) {
      res.status(401).json({ message: 'Неверный email или пароль' });
      return;
    }

    // Проверка активности
    if (!user.is_active) {
      res.status(401).json({ message: 'Аккаунт не активирован' });
      return;
    }

    // Проверка пароля
    const isPasswordValid = await bcrypt.compare(password, user.password_hash);
    if (!isPasswordValid) {
      res.status(401).json({ message: 'Неверный email или пароль' });
      return;
    }

    // Генерация токенов
    const accessToken = generateAccessToken(user.id, user.email || '');
    const refreshToken = generateRefreshToken(user.id);

    res.json({
      message: 'Успешный вход',
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        isActive: user.is_active
      }
    });
  } catch (error) {
    console.error('Signin error:', error);
    res.status(500).json({ message: 'Ошибка сервера при входе' });
  }
};

// Обновление токена
export const refreshToken = async (req: Request, res: Response): Promise<void> => {
  try {
    const { refreshToken } = req.body;

    if (!refreshToken) {
      res.status(401).json({ message: 'Refresh token не предоставлен' });
      return;
    }

    // Проверка refresh token
    const decoded = jwt.verify(
      refreshToken,
      process.env.REFRESH_TOKEN_SECRET_KEY || 'default_refresh_key'
    ) as { id: number };

    // Поиск пользователя
    const user = await userService.findById(decoded.id);
    if (!user || !user.is_active) {
      res.status(401).json({ message: 'Пользователь не найден или не активен' });
      return;
    }

    // Генерация новых токенов
    const newAccessToken = generateAccessToken(user.id, user.email || '');
    const newRefreshToken = generateRefreshToken(user.id);

    res.json({
      accessToken: newAccessToken,
      refreshToken: newRefreshToken
    });
  } catch (error) {
    console.error('Refresh token error:', error);
    res.status(401).json({ message: 'Неверный refresh token' });
  }
};

// Выход
export const signout = async (req: Request, res: Response): Promise<void> => {
  try {
    // Здесь можно добавить удаление refresh token из БД
    res.json({ message: 'Успешный выход' });
  } catch (error) {
    console.error('Signout error:', error);
    res.status(500).json({ message: 'Ошибка сервера' });
  }
};

// Забыли пароль
export const forgotPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { email } = req.body;

    const user = await userService.findByEmail(email);
    if (!user) {
      // Не показываем, существует ли пользователь
      res.json({ message: 'Если пользователь существует, письмо отправлено' });
      return;
    }

    // Генерация токена сброса
    const resetToken = jwt.sign(
      { id: user.id },
      process.env.RESET_PASSWORD_SECRET_KEY || 'default_reset_key',
      { expiresIn: '3m' }
    );

    // Отправка email (реализуйте SendMail)
    const resetLink = `${process.env.CLIENT_BASE_URL}/reset-password?token=${resetToken}`;
    
    // await SendMail({
    //   to: user.email,
    //   subject: 'Сброс пароля',
    //   template: 'resetPassword',
    //   context: { resetLink }
    // });

    res.json({ message: 'Если пользователь существует, письмо отправлено' });
  } catch (error) {
    console.error('Forgot password error:', error);
    res.status(500).json({ message: 'Ошибка сервера' });
  }
};

// Сброс пароля
export const resetPassword = async (req: Request, res: Response): Promise<void> => {
  try {
    const { token, newPassword } = req.body;

    if (!token || !newPassword) {
      res.status(400).json({ message: 'Токен и новый пароль обязательны' });
      return;
    }

    // Проверка токена
    const decoded = jwt.verify(
      token,
      process.env.RESET_PASSWORD_SECRET_KEY || 'default_reset_key'
    ) as { id: number };

    // Обновление пароля
    const hashedPassword = await bcrypt.hash(newPassword, 10);
    await userService.updatePassword(decoded.id, hashedPassword);

    res.json({ message: 'Пароль успешно изменен' });
  } catch (error) {
    console.error('Reset password error:', error);
    res.status(400).json({ message: 'Неверный или истекший токен' });
  }
};

// Подтверждение email
export const verifyEmail = async (req: Request, res: Response): Promise<void> => {
  try {
    const { token } = req.query;

    if (!token) {
      res.status(400).json({ message: 'Токен не предоставлен' });
      return;
    }

    // Проверка и активация пользователя
    const decoded = jwt.verify(
      token as string,
      process.env.ACTIVATION_SECRET_KEY || 'default_activation_key'
    ) as { id: number };

    const user = await userService.findById(decoded.id);
    if (!user) {
      res.status(404).json({ message: 'Пользователь не найден' });
      return;
    }

    // Активация (добавьте метод в userService)
    // await userService.activateUser(decoded.id);

    res.json({ message: 'Email успешно подтвержден' });
  } catch (error) {
    console.error('Verify email error:', error);
    res.status(400).json({ message: 'Неверный или истекший токен' });
  }
};