# VendorEntry.gd
extends Resource
class_name VendorEntry

@export var vendor_id: String = ""
@export var display_name: String = "Merchant"
@export var greeting: String = "What are you buying?"
@export var portrait: Texture2D

@export var shop_listings: Array[ShopListing] = []
