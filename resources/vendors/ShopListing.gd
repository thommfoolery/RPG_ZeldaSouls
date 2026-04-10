# ShopListing.gd
extends Resource
class_name ShopListing

@export var item: GameItem
@export var buy_price: int = 0          # 0 = use item.value * multiplier
@export var sell_price_multiplier: float = 0.3
@export var max_stock: int = 999        # -1 = unlimited
@export var current_stock: int = 0      # saved per vendor

@export var restock_on_rest: bool = false
@export var unlock_after_flag: String = ""      # e.g. "boss_gargoyle_defeated"
@export var is_quest_item_only: bool = false
@export var event_condition_flag: String = ""   # for limited-time stock
