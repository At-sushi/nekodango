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

function Start () {

}

function Update () {

if (Input.GetKey(KeyCode.Escape))
	Application.Quit();
}

function Awake () {
	DontDestroyOnLoad(this.gameObject);
}