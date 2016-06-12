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
var BulletG = null as GameObject;
var BulletW = null as GameObject;
var BulletR = null as GameObject;

function Start () {
	CannonMain();
}

function Update () {

}

// 発射命令
function Fire () {
	var shurui = Random.Range(0,3);
	var direction = new Vector3(-10.0f, Random.Range(20.0f, 30.0f), Random.Range(-5.0f, 5.0f));
	var newBullet = null as GameObject;
	
	switch (shurui)
	{
	case 0:
	 newBullet = Instantiate(BulletG);
	 break;
	case 1:
	 newBullet = Instantiate(BulletW);
	 break;
	default:
	 newBullet = Instantiate(BulletR);
	 break;
	 }
	newBullet.rigidbody.velocity = direction;
}

function CannonMain () {
	for (;;) {
		Fire();
		yield WaitForSeconds (5);
	}
}
