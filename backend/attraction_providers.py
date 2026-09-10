from abc import ABC, abstractmethod
from typing import TYPE_CHECKING, Optional

from bson import ObjectId

if TYPE_CHECKING:
    from server import Attraction


class AttractionProvider(ABC):
    @abstractmethod
    async def search(self, city: str, category: Optional[str] = None) -> list["Attraction"]:
        raise NotImplementedError

    @abstractmethod
    async def get(self, attraction_id: str) -> Optional["Attraction"]:
        raise NotImplementedError


class StaticAttractionProvider(AttractionProvider):
    """Reads curated attractions from the application's MongoDB collection."""

    def __init__(self, collection):
        self.collection = collection

    async def search(self, city: str, category: Optional[str] = None) -> list["Attraction"]:
        city = city.strip()
        query = {"city": city}
        if category:
            query["category"] = category.strip()

        documents = await self.collection.find(query).to_list(100)
        if not documents:
            # Keep the demo provider friendly to casing differences without requiring
            # a live third-party service or a case-sensitive city lookup.
            documents = await self.collection.find({}).to_list(500)
            documents = [
                document for document in documents
                if document.get("city", "").casefold() == city.casefold()
                and (not category or document.get("category", "").casefold() == category.casefold())
            ]
        return [self._model(document) for document in documents]

    async def get(self, attraction_id: str) -> Optional["Attraction"]:
        document = await self.collection.find_one({"_id": attraction_id})
        if document is None:
            try:
                document = await self.collection.find_one({"_id": ObjectId(attraction_id)})
            except Exception:
                document = None
        return self._model(document) if document else None

    @staticmethod
    def _model(document):
        from server import Attraction

        return Attraction.from_mongo(document)
