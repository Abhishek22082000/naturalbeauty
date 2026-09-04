const express = require("express");
const router = express.Router();

const { likePost, unlikePost } = require("../controllers/likeController");
const verifyToken = require("../middlewares/auth");

router.post("/:id/like", verifyToken, likePost);
router.delete("/:id/unlike", verifyToken, unlikePost);

module.exports = router;