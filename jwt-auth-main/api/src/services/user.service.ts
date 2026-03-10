import prisma from '../db/connect.ts';

class UserService {
  async findByEmail(email: string) {
    return await prisma.users.findUnique({
      where: { email: email },
      include: {
        salt: true,
        userRole: {
          include: { role: true }
        }
      }
    });
  }

  async findById(id: number) {
    return await prisma.users.findUnique({
      where: { id: id },
      include: {
        salt: true,
        userRole: {
          include: { role: true }
        }
      }
    });
  }

  async create(email: string, passwordHash: string, saltId: number | null = null) {
    return await prisma.users.create({
      data: {
        email: email,
        password_hash: passwordHash,
        salt_id: saltId,
        is_active: true,
        create_at: new Date()
      }
    });
  }

  async updatePassword(userId: number, newPasswordHash: string) {
    return await prisma.users.update({
      where: { id: userId },
      data: { password_hash: newPasswordHash }
    });
  }
}

export default new UserService();