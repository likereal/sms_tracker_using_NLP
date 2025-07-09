package main

import (
	"github.com/labstack/echo/v4"
	"github.com/redis/go-redis/v9"
)

func NewRedisClient() *redis.Client {
	return redis.NewClient(&redis.Options{
		Addr: "localhost:6379", // Change if your Redis is elsewhere
	})
}

func main() {
	InitRedis()
	e := echo.New()
	hub := NewHub()

	go hub.Run()

	redisClient := NewRedisClient()
	go hub.RedisSubscribe(redisClient)
	hub.RedisClient = redisClient

	e.GET("/ws", WebSocketHandler(hub))

	e.Logger.Fatal(e.Start(":1323"))
}

// import (
// 	"net/http"

// 	"github.com/labstack/echo/v4"
// )

// func main() {
// 	e := echo.New()
// 	e.GET("/", func(c echo.Context) error {
// 		return c.String(http.StatusOK, "Hello, World!")
// 	})
// 	e.Logger.Fatal(e.Start(":1323"))
// }
