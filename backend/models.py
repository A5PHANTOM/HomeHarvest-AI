from sqlalchemy import Column, Integer, String, Float
from database import Base

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    email = Column(String, unique=True, index=True)
    hashed_password = Column(String)


class MarketplaceItem(Base):
    __tablename__ = "marketplace_items"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    price = Column(String, nullable=False)
    distance = Column(String, nullable=False)
    seller = Column(String, nullable=False)
    time_posted = Column(String, nullable=False)


class Reminder(Base):
    __tablename__ = "reminders"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    time = Column(String, nullable=False)
    icon = Column(String, nullable=False)
    color = Column(String, nullable=False)


class GardenCalendarItem(Base):
    __tablename__ = "garden_calendar_items"

    id = Column(Integer, primary_key=True, index=True)
    plant = Column(String, nullable=False)
    action = Column(String, nullable=False)
    days = Column(String, nullable=False)
    progress = Column(Float, nullable=False, default=0.0)
    color = Column(String, nullable=False)
