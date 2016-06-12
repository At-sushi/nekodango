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
import UnityEngine.UI;
import UnityEngine;
static var score = 0;
static var lastHit = -10;
static var lastlastHit = -10;
var timeLimit = 100;
private static var startTime : float;

function Start () {
	// タイムスタンプを切る
	startTime = Time.time;
	score = 0;
	lastHit = -10;
	lastlastHit = -10;
}

function Update () {
	var msg = GameObject.Find("Canvas/Score").GetComponent("Text") as Text;
	var restTime = timeLimit - Mathf.Floor(Time.time - startTime);
	if (restTime < 0)
	{
	var panel = GameObject.Find("Canvas") as GameObject;
		panel = panel.transform.FindChild("Panel").gameObject;
	    panel.SetActive(true);
	var text = GameObject.Find("Canvas/Panel/Text").GetComponent("Text") as Text;
	    text.text = "Score : " + score;
	    GameObject.Find("Canvas/Score").SetActive(false);
	}
	else
		msg.text = "Time : " + restTime + "\nScore : " + score;
}

public function osu()
{
	Application.LoadLevel("gohdr");
}
