from pydantic import BaseModel, EmailStr, Field


class LoginRequest(BaseModel):
    """Schema đăng nhập"""
    email: EmailStr
    password: str = Field(..., min_length=6)


class RegisterRequest(BaseModel):
    """Schema đăng ký"""
    email: EmailStr
    password: str = Field(..., min_length=6)
    display_name: str = Field(..., min_length=2, max_length=100)


class TokenResponse(BaseModel):
    """Schema response token"""
    token: str
    token_type: str = "bearer"


class AuthResponse(BaseModel):
    """Schema response xác thực"""
    user: dict
    token: str
    message: str = "Thành công"
