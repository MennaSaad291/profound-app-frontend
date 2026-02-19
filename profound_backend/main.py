from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from passlib.context import CryptContext

# Database configuration
DATABASE_URL = "postgresql://postgres:Menna@2901@localhost:5432/profound_db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

app = FastAPI()

# Database Model
class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)

Base.metadata.create_all(bind=engine)

# Pydantic Schemas
class UserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

@app.post("/register")
def register_user(user: UserCreate):
    db = SessionLocal()
    # Check if user exists
    db_user = db.query(UserDB).filter(UserDB.email == user.email).first()
    if db_user:
        db.close()
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Hash password and save
    hashed_password = pwd_context.hash(user.password)
    new_user = UserDB(full_name=user.full_name, email=user.email, password_hash=hashed_password)
    db.add(new_user)
    db.commit()
    db.close()
    return {"message": "User created successfully"}