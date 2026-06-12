from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from ..database import get_db
from ..schemas.auth import LoginRequest, RegisterRequest, AuthResponse
from ..services.auth_service import AuthService
from ..dependencies import get_current_user
from ..models.user import User

router = APIRouter()


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
async def register(
    request: RegisterRequest,
    db: AsyncSession = Depends(get_db)
):
    """Đăng ký tài khoản mới"""
    user = await AuthService.register(
        db=db,
        email=request.email,
        password=request.password,
        display_name=request.display_name
    )
    
    token = AuthService.create_access_token(user.id)
    
    return AuthResponse(
        user=user.to_dict(),
        token=token,
        message="Đăng ký thành công"
    )


@router.post("/login", response_model=AuthResponse)
async def login(
    request: LoginRequest,
    db: AsyncSession = Depends(get_db)
):
    """Đăng nhập"""
    user = await AuthService.login(
        db=db,
        email=request.email,
        password=request.password
    )
    
    token = AuthService.create_access_token(user.id)
    
    return AuthResponse(
        user=user.to_dict(),
        token=token,
        message="Đăng nhập thành công"
    )


@router.post("/logout")
async def logout(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """Đăng xuất"""
    await AuthService.logout(db, current_user.id)
    
    return {"message": "Đăng xuất thành công"}


@router.get("/me")
async def get_me(current_user: User = Depends(get_current_user)):
    """Lấy thông tin user hiện tại"""
    return {"user": current_user.to_dict()}
