from abc import ABC, abstractmethod


class PhoneOtpProvider(ABC):
    @abstractmethod
    async def request_code(self, phone_number: str) -> None:
        raise NotImplementedError

    @abstractmethod
    async def verify_code(self, phone_number: str, code: str) -> bool:
        raise NotImplementedError


class AppleAuthProvider(ABC):
    @abstractmethod
    async def verify_identity_token(self, identity_token: str) -> dict:
        raise NotImplementedError