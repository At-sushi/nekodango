/*
    黒猫のあんまり関係ないダンゴ
    Copyright (C) 2015 At-sushi

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma strict
var type : int;
static var combo = 2;
function Start () {
	combo = 2;
}

function Update () {
	// 止まったら壊す
	if (rigidbody.IsSleeping())
		Destroy(gameObject);
}

function OnTriggerEnter (collisionInfo : Collider) {
	var se = GameObject.Find("se_maoudamashii_system46") as GameObject;
	if (Score.lastHit == type)
	{
	Score.score += 10 * combo++;
	Score.lastlastHit = Score.lastHit;
	Score.lastHit = type;
	}
	else if (Score.lastlastHit + Score.lastHit + type == 3)
	{
		Score.score += 100;
		Score.lastlastHit = -10;
		Score.lastHit = -10;
		combo = 2;
	}
	else
	{
	Score.score += 10;
	Score.lastlastHit = Score.lastHit;
	Score.lastHit = type;
	combo = 2;
	}
	se.audio.Play();
    Destroy(gameObject);
}
