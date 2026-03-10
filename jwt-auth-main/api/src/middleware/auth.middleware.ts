import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import prisma from '../db/connect.ts';

// Расширяем интерфейс Request
export interface AuthRequest extends Request {
  user?: {
    id: number;
    email: string;
  };
}

export const authMiddleware = async (
  req: AuthRequest,
  res: Response,
  next: NextFunction
): Promise<void> => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      res.status(401).json({ message: 'Токен не предоставлен' });
      return;
    }

    const token = authHeader.split(' ')[1];
    const decoded = jwt.verify(
      token,
      process.env.ACCESS_TOKEN_SECRET_KEY || 'default_access_key'
    ) as { id: number; email: string };

    const user = await prisma.users.findUnique({
      where: { id: decoded.id },
      select: {
        id: true,
        email: true,
        is_active: true
      }
    });

    if (!user || !user.is_active) {
      res.status(401).json({ message: 'Пользователь не найден или не активен' });
      return;
    }

    req.user = {
      id: user.id,
      email: user.email || ''
    };

    next();
  } catch (error) {
    console.error('Auth middleware error:', error);
    res.status(401).json({ message: 'Неверный токен' });
  }
};