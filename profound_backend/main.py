import bcrypt 
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, EmailStr
from sqlalchemy import create_engine, Column, Integer, String
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

# --- Database Config ---
DATABASE_URL = "postgresql://postgres:Menna%402901@localhost:5432/profound_db"
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

app = FastAPI()

# --- Model ---
class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    full_name = Column(String)
    email = Column(String, unique=True, index=True)
    password_hash = Column(String)

Base.metadata.create_all(bind=engine)

# --- Schemas ---
class UserCreate(BaseModel):
    full_name: str
    email: EmailStr
    password: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

# --- Endpoints ---

@app.post("/register")
def register_user(user: UserCreate):
    db = SessionLocal()
    try:
        db_user = db.query(UserDB).filter(UserDB.email == user.email).first()
        if db_user:
            raise HTTPException(status_code=400, detail="Email already registered")
        
        salt = bcrypt.gensalt()
        hashed_password = bcrypt.hashpw(user.password.encode('utf-8'), salt).decode('utf-8')
        
        new_user = UserDB(full_name=user.full_name, email=user.email, password_hash=hashed_password)
        db.add(new_user)
        db.commit()
        return {"message": "User created successfully"}
    finally:
        db.close()

@app.post("/login")
def login_user(user: UserLogin):
    db = SessionLocal()
    try:
        db_user = db.query(UserDB).filter(UserDB.email == user.email).first()
        
        if not db_user:
            raise HTTPException(status_code=401, detail="Invalid email or password")
        
        is_valid = bcrypt.checkpw(
            user.password.encode('utf-8'), 
            db_user.password_hash.encode('utf-8')
        )
        
        if not is_valid:
            raise HTTPException(status_code=401, detail="Invalid email or password")
            
        return {"message": "Login successful", "user": {"id": db_user.id, "name": db_user.full_name}}
    finally:
        db.close()