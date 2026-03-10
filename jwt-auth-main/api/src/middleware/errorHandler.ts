import { NextFunction, Response, Request } from "express";
import ErrorResponse from "../utils/ErrorResponse.ts";
import jwt from "jsonwebtoken";

interface PrismaError extends Error {
  code?: string;
  meta?: {
    modelName?: string;
    field?: string;
  };
}

export const errorHandler = (
  error: unknown,
  req: Request,
  res: Response,
  next: NextFunction
): void => {
  let err: unknown;
  let status: number;
  
  if (error instanceof ErrorResponse) {
    status = error.statusCode;
    err = {
      name: error.name,
      message: error.message,
    };
  } else if (error instanceof jwt.JsonWebTokenError) {
    status = 401;
    err = {
      name: error.name,
      message: error.message,
    };
  } else if (error instanceof jwt.TokenExpiredError) {
    status = 401;
    err = {
      name: "TokenExpiredError",
      message: "Token has expired",
    };
  } else if (error instanceof Error && (error as PrismaError).code) {
    const prismaError = error as PrismaError;
    
    switch (prismaError.code) {
      case "P2002":
        status = 409;
        err = {
          name: "PrismaError",
          message: `Unique constraint failed: ${prismaError.meta?.field || "field"}`,
        };
        break;
      case "P2025":
        status = 404;
        err = {
          name: "PrismaError",
          message: "Record not found",
        };
        break;
      case "P2003":
        status = 400;
        err = {
          name: "PrismaError",
          message: "Foreign key constraint failed",
        };
        break;
      default:
        status = 500;
        err = {
          name: "PrismaError",
          message: "Database error",
        };
    }
  } else if (error instanceof Error && error.name === "ValidationError") {
    const errors: any = {};
    if ("errors" in error) {
      const validationErrors = (error as any).errors;
      if (validationErrors && typeof validationErrors === "object") {
        Object.keys(validationErrors).forEach((key) => {
          errors[key] = validationErrors[key].message || validationErrors[key];
        });
      }
    }
    
    status = 400;
    err = {
      name: "ValidationError",
      message: "Validation Error",
      errors,
    };
  } else {
    status = 500;
    err = error instanceof Error ? error.message : "Internal server error";
  }

  res.status(status).json({
    success: false,
    error: err,
  });
};

export const notFound = (req: Request, res: Response, next: NextFunction): void => {
  const error = new Error(`Route not found - ${req.originalUrl}`) as any;
  error.statusCode = 404;
  next(error);
};

export default errorHandler;